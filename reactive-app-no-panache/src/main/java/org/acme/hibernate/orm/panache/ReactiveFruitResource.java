package org.acme.hibernate.orm.panache;

import static javax.ws.rs.core.Response.Status.CREATED;

import java.util.List;

import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;

import org.hibernate.reactive.mutiny.Mutiny;
import org.jboss.resteasy.reactive.RestPath;

import io.smallrye.mutiny.Uni;

@Path("fruits")
@ApplicationScoped
@Produces("application/json")
@Consumes("application/json")
public class ReactiveFruitResource {

    @Inject
    Mutiny.SessionFactory sf; 

    @GET
    public Uni<List<Fruit>> get() {
        return sf.withTransaction((s,t) -> s
                .createNamedQuery("Fruits.findAll", Fruit.class)
                .getResultList()
        );
    }


    @GET
    @Path("{id}")
    public Uni<Fruit> getSingle(@RestPath Long id) {
        return sf.withTransaction((s,t) -> s.find(Fruit.class, id));
    }

    @POST
    public Uni<Response> create(Fruit fruit) {
        if (fruit == null || fruit.getId() != null) {
            throw new WebApplicationException("Id was invalidly set on request.", 422);
        }

        return sf.withTransaction((s,t) -> s.persist(fruit))
                .replaceWith(() -> Response.ok(fruit).status(CREATED).build());
    }

}
