from flask import Flask, render_template, request, redirect, url_for, session, Response
from werkzeug.security import check_password_hash
import psycopg2
import os
import csv
import io
from datetime import datetime
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash

load_dotenv()

app = Flask(__name__)

app.secret_key = os.environ.get("AUTOAUDIT_SECRET_KEY") or os.urandom(32)

ADMIN_USUARIO = os.environ.get("AUTOAUDIT_ADMIN_USER", "admin")
ADMIN_PASSWORD = os.environ.get("AUTOAUDIT_ADMIN_PASSWORD", "")
ADMIN_PASSWORD_HASH = generate_password_hash(ADMIN_PASSWORD) if ADMIN_PASSWORD else None


def conectar_bd():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "localhost"),
        database=os.environ.get("DB_NAME", "sistema_academico"),
        user=os.environ.get("DB_USER", "postgres"),
        password=os.environ.get("DB_PASSWORD", ""),
        port=os.environ.get("DB_PORT", "5432")
    )


def obtener_tablas(cursor):
    cursor.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name NOT IN (
            'bitacora',
            'columnas_auditadas',
            'configuracion_auditoria',
            'estacion_de_trabajo',
            'eventos',
            'tablas_auditadas',
            'usuarios_auditados'
        )
        ORDER BY table_name;
    """)

    return [fila[0] for fila in cursor.fetchall()]


def obtener_columnas(cursor, tabla):
    cursor.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = %s
        ORDER BY ordinal_position;
    """, (tabla,))

    return [fila[0] for fila in cursor.fetchall()]


def obtener_configuracion(cursor, tabla):
    cursor.execute("""
        SELECT
            ca.nombre_columna,
            e.nombre_evento,
            co.activa
        FROM configuracion_auditoria co
        JOIN columnas_auditadas ca
            ON co.id_columna = ca.id_columna
        JOIN tablas_auditadas ta
            ON ca.id_tabla = ta.id_tabla
        JOIN eventos e
            ON co.id_evento = e.id_evento
        WHERE ta.esquema = 'public'
        AND ta.nombre_tabla = %s;
    """, (tabla,))

    filas = cursor.fetchall()

    configuracion = {}

    for columna, evento, activa in filas:

        if columna not in configuracion:
            configuracion[columna] = {
                "INSERT": False,
                "UPDATE": False,
                "DELETE": False
            }

        if activa:
            configuracion[columna][evento] = True

    return configuracion


@app.route("/login", methods=["GET", "POST"])
def login():

    if session.get("administrador"):
        return redirect(url_for("inicio"))

    mensaje = None

    if request.method == "POST":

        usuario = request.form.get("usuario", "").strip()
        password = request.form.get("password", "")

        if (
            usuario == ADMIN_USUARIO
            and ADMIN_PASSWORD_HASH is not None
            and check_password_hash(
                ADMIN_PASSWORD_HASH,
                password
            )
        ):
            session["administrador"] = True
            session["usuario"] = usuario

            return redirect(url_for("inicio"))

        mensaje = "Usuario o contraseña incorrectos."

    return render_template(
        "login.html",
        mensaje=mensaje
    )


@app.route("/logout")
def logout():

    session.clear()

    return redirect(url_for("login"))


@app.route("/", methods=["GET", "POST"])
def inicio():

    if not session.get("administrador"):
        return redirect(url_for("login"))

    conexion = conectar_bd()
    cursor = conexion.cursor()

    tablas = obtener_tablas(cursor)

    tabla_seleccionada = None
    columnas = []
    configuracion = {}
    mensaje = None
    auditoria_activa_actual = True

    if request.method == "POST":

        accion = request.form.get("accion")
        tabla_seleccionada = request.form.get("tabla")

        if tabla_seleccionada not in tablas:

            mensaje = "La tabla seleccionada no existe."

        else:

            columnas = obtener_columnas(
                cursor,
                tabla_seleccionada
            )

            cursor.execute("SELECT activa FROM tablas_auditadas WHERE esquema = %s AND nombre_tabla = %s", ("public", tabla_seleccionada))
            fila_estado = cursor.fetchone()
            if fila_estado is not None:
                auditoria_activa_actual = fila_estado[0]

            if accion == "cargar":

                configuracion = obtener_configuracion(
                    cursor,
                    tabla_seleccionada
                )

            elif accion == "guardar":

                columnas_seleccionadas = request.form.getlist(
                    "columnas"
                )

                auditar_insert = "insert" in request.form
                auditar_update = "update" in request.form
                auditar_delete = "delete" in request.form

                auditoria_activa = (
                    "auditoria_activa" in request.form
                )

                if not columnas_seleccionadas:

                    mensaje = (
                        "Debe seleccionar al menos una columna."
                    )

                elif not (
                    auditar_insert
                    or auditar_update
                    or auditar_delete
                ):

                    mensaje = (
                        "Debe seleccionar al menos una operación."
                    )

                elif not all(
                    columna in columnas
                    for columna in columnas_seleccionadas
                ):

                    mensaje = (
                        "Una de las columnas seleccionadas "
                        "no existe."
                    )

                else:

                    try:

                        cursor.execute("""
                            INSERT INTO tablas_auditadas (
                                esquema,
                                nombre_tabla,
                                activa
                            )
                            VALUES (
                                'public',
                                %s,
                                %s
                            )
                            ON CONFLICT (
                                esquema,
                                nombre_tabla
                            )
                            DO UPDATE
                            SET activa = EXCLUDED.activa
                            RETURNING id_tabla;
                        """, (
                            tabla_seleccionada,
                            auditoria_activa
                        ))

                        id_tabla = cursor.fetchone()[0]

                        cursor.execute("""
                            UPDATE configuracion_auditoria
                            SET activa = FALSE
                            WHERE id_columna IN (
                                SELECT id_columna
                                FROM columnas_auditadas
                                WHERE id_tabla = %s
                            );
                        """, (id_tabla,))

                        for columna in columnas_seleccionadas:

                            cursor.execute("""
                                INSERT INTO columnas_auditadas (
                                    id_tabla,
                                    nombre_columna,
                                    activa
                                )
                                VALUES (
                                    %s,
                                    %s,
                                    %s
                                )
                                ON CONFLICT (
                                    id_tabla,
                                    nombre_columna
                                )
                                DO UPDATE
                                SET activa = EXCLUDED.activa
                                RETURNING id_columna;
                            """, (
                                id_tabla,
                                columna,
                                auditoria_activa
                            ))

                            id_columna = cursor.fetchone()[0]

                            operaciones = []

                            if auditar_insert:
                                operaciones.append("INSERT")

                            if auditar_update:
                                operaciones.append("UPDATE")

                            if auditar_delete:
                                operaciones.append("DELETE")

                            for operacion in operaciones:

                                cursor.execute("""
                                    SELECT id_evento
                                    FROM eventos
                                    WHERE nombre_evento = %s;
                                """, (operacion,))

                                resultado = cursor.fetchone()

                                if resultado is None:
                                    raise Exception(
                                        "No existe el evento "
                                        + operacion
                                    )

                                id_evento = resultado[0]

                                cursor.execute("""
                                    SELECT id_configuracion
                                    FROM configuracion_auditoria
                                    WHERE id_columna = %s
                                    AND id_evento = %s
                                    LIMIT 1;
                                """, (
                                    id_columna,
                                    id_evento
                                ))

                                existente = cursor.fetchone()

                                if existente:

                                    cursor.execute("""
                                        UPDATE configuracion_auditoria
                                        SET
                                            auditar_insert = %s,
                                            auditar_update = %s,
                                            auditar_delete = %s,
                                            activa = %s
                                        WHERE id_configuracion = %s;
                                    """, (
                                        operacion == "INSERT",
                                        operacion == "UPDATE",
                                        operacion == "DELETE",
                                        auditoria_activa,
                                        existente[0]
                                    ))

                                else:

                                    cursor.execute("""
                                        INSERT INTO
                                        configuracion_auditoria (
                                            id_columna,
                                            id_evento,
                                            auditar_insert,
                                            auditar_update,
                                            auditar_delete,
                                            activa
                                        )
                                        VALUES (
                                            %s,
                                            %s,
                                            %s,
                                            %s,
                                            %s,
                                            %s
                                        );
                                    """, (
                                        id_columna,
                                        id_evento,
                                        operacion == "INSERT",
                                        operacion == "UPDATE",
                                        operacion == "DELETE",
                                        auditoria_activa
                                    ))

                        conexion.commit()
                        auditoria_activa_actual = auditoria_activa

                        mensaje = (
                            "Configuración actualizada "
                            "correctamente."
                        )

                        configuracion = obtener_configuracion(
                            cursor,
                            tabla_seleccionada
                        )

                    except Exception as error:

                        conexion.rollback()

                        mensaje = (
                            "Error al guardar: "
                            + str(error)
                        )

    cursor.close()
    conexion.close()

    return render_template(
        "index.html",
        tablas=tablas,
        tabla_seleccionada=tabla_seleccionada,
        columnas=columnas,
        configuracion=configuracion,
        mensaje=mensaje,
        usuario=session.get("usuario"),
        auditoria_activa_actual=auditoria_activa_actual
    )


@app.route("/reportes")
def reportes():
    if not session.get("administrador"):
        return redirect(url_for("login"))
    tabla = request.args.get("tabla", "").strip()
    accion = request.args.get("accion", "").strip().upper()
    usuario = request.args.get("usuario", "").strip()
    desde = request.args.get("desde", "").strip()
    hasta = request.args.get("hasta", "").strip()
    condiciones = []
    parametros = []
    if tabla:
        condiciones.append("tabla_modificada = %s")
        parametros.append(tabla)
    if accion in ("INSERT", "UPDATE", "DELETE"):
        condiciones.append("accion_realizada = %s")
        parametros.append(accion)
    if usuario:
        condiciones.append("user_auditado ILIKE %s")
        parametros.append("%" + usuario + "%")
    if desde:
        try:
            datetime.strptime(desde, "%Y-%m-%d")
            condiciones.append("fecha_hora >= %s::date")
            parametros.append(desde)
        except ValueError:
            desde = ""
    if hasta:
        try:
            datetime.strptime(hasta, "%Y-%m-%d")
            condiciones.append("fecha_hora < (%s::date + interval '1 day')")
            parametros.append(hasta)
        except ValueError:
            hasta = ""
    where = " WHERE " + " AND ".join(condiciones) if condiciones else ""
    sql = ("SELECT id_bitacora, fecha_hora, user_auditado, tabla_modificada, "
           "columna_modificada, accion_realizada, dato_anterior, dato_nuevo "
           "FROM bitacora" + where + " ORDER BY fecha_hora DESC, id_bitacora DESC LIMIT 1000")
    with conectar_bd() as conexion:
        with conexion.cursor() as cursor:
            cursor.execute(sql, parametros)
            filas = cursor.fetchall()
    if request.args.get("exportar") == "csv":
        salida = io.StringIO()
        escritor = csv.writer(salida, delimiter=";", lineterminator="\r\n")
        escritor.writerow(["ID", "Fecha", "Usuario", "Tabla", "Columna", "Accion", "Anterior", "Nuevo"])
        escritor.writerows(filas)
        return Response("\ufeffsep=;\r\n" + salida.getvalue(), mimetype="text/csv; charset=utf-8",
                        headers={"Content-Disposition": "attachment; filename=autoaudit_reporte.csv"})
    return render_template("reportes.html", filas=filas, filtros={
        "tabla": tabla, "accion": accion, "usuario": usuario, "desde": desde, "hasta": hasta
    }, usuario_sesion=session.get("usuario"))

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "5000")), debug=False)